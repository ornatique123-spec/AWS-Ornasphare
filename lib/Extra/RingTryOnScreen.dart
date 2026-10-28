// import 'dart:convert';
// import 'dart:io';
// import 'dart:typed_data';
//
// import 'package:dio/dio.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_inappwebview/flutter_inappwebview.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:share_plus/share_plus.dart';
//
// /// ================================================================
// /// 🔥 TRY-ON PAGES
// /// HTML ને asset માંથી વાંચીને સીધું WebView માં મૂકીએ છીએ,
// /// base URL "https://localhost/" સાથે. એટલે:
// ///   • http / cleartext ની તકલીફ નહીં (ERR_CLEARTEXT_NOT_PERMITTED)
// ///   • localhost server ની જરૂર નહીં
// ///   • page "secure" ગણાય → camera (getUserMedia) ચાલે
// /// ================================================================
// class TryOnPages {
//   /// HTML files જે folder માં છે (pubspec.yaml માં પણ આ જ folder)
//   static const String assetFolder = "assets/static";
//
//   static const String ringPage = "$assetFolder/ring_tryon.html";
//   static const String chainPage = "$assetFolder/chain_tryon.html";
//
//   static const String baseUrl = "https://localhost/";
// }
//
// /// 🔥 કયો દાગીનો
// enum TryOnType { ring, chain }
//
// /// ================================================================
// /// 🔥 JEWELLERY TRY-ON SCREEN (Ring + Chain)
// ///
// /// type      : TryOnType.ring  → હાથ (MediaPipe Hands)
// ///             TryOnType.chain → ચહેરો + ગળું (MediaPipe Face), selfie camera
// /// imageUrl  : https://... (ERP ની try-on PNG) અથવા asset path
// /// anchorX/Y : PNG માં anchor (0..1)
// ///             Ring  → band નું center
// ///             Chain → બે hook વચ્ચેનું ઉપરનું center
// /// bandWidth : Ring  → band ની પહોળાઈ / image પહોળાઈ
// ///             Chain → બે hook વચ્ચેની પહોળાઈ / image પહોળાઈ
// ///
// /// Demo defaults:
// ///   ring_*.png  (600x300) → 0.5, 0.567, 0.867
// ///   chain_gold.png (800x520) → 0.5, 0.077, 0.75
// /// ================================================================
// class RingTryOnScreen extends StatefulWidget {
//   /// null હોય તો image ના નામ પરથી: "chain" / "necklace" → chain, બાકી ring
//   final TryOnType? type;
//   final String imageUrl;
//   final String itemName;
//   final double? anchorX;
//   final double? anchorY;
//   final double? bandWidth;
//
//   const RingTryOnScreen({
//     super.key,
//     this.type,
//     required this.imageUrl,
//     this.itemName = "Jewellery",
//     this.anchorX,
//     this.anchorY,
//     this.bandWidth,
//   });
//
//   @override
//   State<RingTryOnScreen> createState() => _RingTryOnScreenState();
// }
//
// class _RingTryOnScreenState extends State<RingTryOnScreen> {
//   bool get _isChain {
//     if (widget.type != null) return widget.type == TryOnType.chain;
//     final String name = widget.imageUrl.toLowerCase();
//     return name.contains("chain") || name.contains("necklace");
//   }
//
//   double get _anchorX => widget.anchorX ?? 0.5;
//   double get _anchorY => widget.anchorY ?? (_isChain ? 0.077 : 0.567);
//   double get _bandWidth => widget.bandWidth ?? (_isChain ? 0.75 : 0.867);
//
//   String get _pagePath =>
//       _isChain ? TryOnPages.chainPage : TryOnPages.ringPage;
//
//   /// Asset માંથી વાંચેલું HTML
//   String? _pageHtml;
//
//   static const Color _navy = Color(0xff0D2A5C);
//   static const Color _blue = Color(0xff1E6FE8);
//
//   InAppWebViewController? _web;
//
//   bool _preparing = true;
//   String? _error;
//
//   /// Ring image → data URI (canvas photo માં CORS તકલીફ ના આવે)
//   String? _ringDataUri;
//
//   String _status = "Opening try-on…";
//
//   /// Page માંથી કોઈ message આવ્યો? (ના આવે તો watchdog error બતાવે)
//   bool _gotMessageFromPage = false;
//   double _size = 1.0;
//
//   /// Chain ઉપર-નીચે (−1 ઉપર, +1 નીચે)
//   double _offset = 0.0;
//   bool _showPoints = false;
//   bool _sharing = false;
//
//   /// HTML page સાચી રીતે load થયું અને JS તૈયાર છે
//   bool _pageReady = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _prepare();
//   }
//
//   /// =========================================================
//   /// PERMISSION + SERVER + RING IMAGE
//   /// =========================================================
//   Future<void> _prepare() async {
//     try {
//       final PermissionStatus cam = await Permission.camera.request();
//
//       if (!cam.isGranted) {
//         setState(() {
//           _preparing = false;
//           _error = cam.isPermanentlyDenied
//               ? "Camera permission is off. Turn it on in app settings."
//               : "Camera permission is needed for try-on.";
//         });
//         return;
//       }
//
//       /// 🔥 HTML asset માંથી વાંચો
//       _pageHtml = await rootBundle.loadString(_pagePath);
//       debugPrint("📄 TRYON PAGE LOADED FROM ASSET => $_pagePath (${_pageHtml!.length} chars)");
//
//       _ringDataUri = await _loadImageAsDataUri(widget.imageUrl);
//
//       if (!mounted) return;
//       setState(() => _preparing = false);
//
//       /// 🔥 WATCHDOG: 20 સેકન્ડમાં page કંઈ ના બોલે તો કારણ બતાવો
//       Future.delayed(const Duration(seconds: 20), () {
//         if (!mounted || _gotMessageFromPage || _error != null) return;
//         setState(() {
//           _error = "Try-on page did not respond.\n"
//               "Check internet connection and that "
//               "${TryOnPages.assetFolder}/ is in pubspec.yaml.";
//         });
//       });
//     } catch (e) {
//       debugPrint("❌ TRY-ON PREPARE ERROR => $e");
//       if (!mounted) return;
//       setState(() {
//         _preparing = false;
//         _error = e.toString().contains("Unable to load asset")
//             ? "Try-on page not found: $_pagePath\nAdd it to assets and pubspec.yaml."
//             : "Could not open try-on. Please try again.";
//       });
//     }
//   }
//
//   Future<String> _loadImageAsDataUri(String path) async {
//     late Uint8List bytes;
//
//     if (path.startsWith("http")) {
//       final response = await Dio().get<List<int>>(
//         path,
//         options: Options(responseType: ResponseType.bytes),
//       );
//       bytes = Uint8List.fromList(response.data ?? []);
//     } else {
//       final data = await rootBundle.load(path);
//       bytes = data.buffer.asUint8List();
//     }
//
//     return "data:image/png;base64,${base64Encode(bytes)}";
//   }
//
//   /// =========================================================
//   /// FLUTTER → JS
//   /// =========================================================
//   Future<void> _sendRing() async {
//     if (_web == null || _ringDataUri == null || !_pageReady) return;
//
//     final String cfg = jsonEncode({
//       "src": _ringDataUri,
//       "anchorX": _anchorX,
//       "anchorY": _anchorY,
//       "bandWidth": _bandWidth,
//     });
//
//     /// 🔥 function હોય તો જ બોલાવો (error page પર crash નહીં)
//     await _web!.evaluateJavascript(
//       source: "if (typeof window.setRing === 'function') { window.setRing($cfg); }",
//     );
//     await _web!.evaluateJavascript(
//       source: "if (typeof window.setSize === 'function') { window.setSize($_size); }",
//     );
//     if (_isChain) {
//       await _web!.evaluateJavascript(
//         source:
//         "if (typeof window.setOffset === 'function') { window.setOffset($_offset); }",
//       );
//     }
//   }
//
//   Future<void> _js(String code) async {
//     if (!_pageReady) return;
//     try {
//       await _web?.evaluateJavascript(source: code);
//     } catch (e) {
//       debugPrint("JS ERROR => $e");
//     }
//   }
//
//   /// =========================================================
//   /// PHOTO (JS → Flutter) → WhatsApp / Share
//   /// =========================================================
//   Future<void> _onPhoto(String dataUrl) async {
//     try {
//       final String b64 = dataUrl.substring(dataUrl.indexOf(",") + 1);
//       final Uint8List bytes = base64Decode(b64);
//
//       final Directory dir = await getTemporaryDirectory();
//       final File file = File(
//         "${dir.path}/${_isChain ? "chain" : "ring"}_tryon_${DateTime.now().millisecondsSinceEpoch}.png",
//       );
//       await file.writeAsBytes(bytes);
//
//       await Share.shareXFiles(
//         [XFile(file.path)],
//         text: widget.itemName,
//       );
//     } catch (e) {
//       debugPrint("❌ PHOTO ERROR => $e");
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text("Could not save photo")),
//         );
//       }
//     } finally {
//       if (mounted) setState(() => _sharing = false);
//     }
//   }
//
//   /// =========================================================
//   /// BUILD
//   /// =========================================================
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       body: Stack(
//         children: [
//           /// CAMERA + RING (WebView)
//           Positioned.fill(child: _buildBody()),
//
//           /// TOP BAR
//           Positioned(
//             top: 0,
//             left: 0,
//             right: 0,
//             child: SafeArea(
//               bottom: false,
//               child: Padding(
//                 padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
//                 child: Row(
//                   children: [
//                     _roundIcon(
//                       Icons.arrow_back_rounded,
//                           () => Navigator.pop(context),
//                     ),
//                     const SizedBox(width: 10),
//                     Expanded(
//                       child: Container(
//                         padding: const EdgeInsets.symmetric(
//                           horizontal: 12,
//                           vertical: 9,
//                         ),
//                         decoration: BoxDecoration(
//                           color: Colors.black.withOpacity(0.45),
//                           borderRadius: BorderRadius.circular(10),
//                         ),
//                         child: Text(
//                           widget.itemName,
//                           maxLines: 1,
//                           overflow: TextOverflow.ellipsis,
//                           style: const TextStyle(
//                             color: Colors.white,
//                             fontSize: 14,
//                             fontWeight: FontWeight.w700,
//                           ),
//                         ),
//                       ),
//                     ),
//                     const SizedBox(width: 10),
//                     _roundIcon(
//                       Icons.cameraswitch_rounded,
//                           () => _js("window.flipCamera();"),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//
//           /// STATUS
//           if (_error == null && !_preparing && _status.isNotEmpty)
//             Positioned(
//               left: 0,
//               right: 0,
//               top: MediaQuery.of(context).padding.top + 70,
//               child: Center(
//                 child: Container(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 14,
//                     vertical: 8,
//                   ),
//                   decoration: BoxDecoration(
//                     color: Colors.black.withOpacity(0.55),
//                     borderRadius: BorderRadius.circular(20),
//                   ),
//                   child: Text(
//                     _status,
//                     style: const TextStyle(color: Colors.white, fontSize: 13),
//                   ),
//                 ),
//               ),
//             ),
//
//           /// BOTTOM CONTROLS
//           if (_error == null && !_preparing)
//             Positioned(
//               left: 0,
//               right: 0,
//               bottom: 0,
//               child: _bottomControls(),
//             ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildBody() {
//     if (_preparing) {
//       return const Center(
//         child: CircularProgressIndicator(color: Colors.white),
//       );
//     }
//
//     if (_error != null) {
//       return Center(
//         child: Padding(
//           padding: const EdgeInsets.all(24),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               const Icon(
//                 Icons.no_photography_outlined,
//                 color: Colors.white70,
//                 size: 48,
//               ),
//               const SizedBox(height: 12),
//               Text(
//                 _error!,
//                 textAlign: TextAlign.center,
//                 style: const TextStyle(color: Colors.white, fontSize: 14),
//               ),
//               const SizedBox(height: 16),
//               ElevatedButton(
//                 onPressed: () async {
//                   if (_error!.contains("settings")) {
//                     await openAppSettings();
//                   }
//                   setState(() {
//                     _preparing = true;
//                     _error = null;
//                     _pageReady = false;
//                     _gotMessageFromPage = false;
//                     _status = "Opening try-on…";
//                   });
//                   _prepare();
//                 },
//                 child: const Text("Try again"),
//               ),
//             ],
//           ),
//         ),
//       );
//     }
//
//     return InAppWebView(
//       /// 🔥 HTML સીધું (http server વગર), secure base URL સાથે
//       initialData: InAppWebViewInitialData(
//         data: _pageHtml ?? "",
//         baseUrl: WebUri(TryOnPages.baseUrl),
//         mimeType: "text/html",
//         encoding: "utf-8",
//       ),
//       initialSettings: InAppWebViewSettings(
//         javaScriptEnabled: true,
//         mediaPlaybackRequiresUserGesture: false,
//         allowsInlineMediaPlayback: true,
//         transparentBackground: true,
//         supportZoom: false,
//       ),
//       onWebViewCreated: (controller) {
//         _web = controller;
//
//         controller.addJavaScriptHandler(
//           handlerName: "ready",
//           callback: (args) {
//             _gotMessageFromPage = true;
//             _pageReady = true;
//             _sendRing();
//             return null;
//           },
//         );
//
//         controller.addJavaScriptHandler(
//           handlerName: "status",
//           callback: (args) {
//             _gotMessageFromPage = true;
//             if (!mounted) return null;
//             setState(() {
//               _status = args.isNotEmpty ? args.first.toString() : "";
//             });
//             return null;
//           },
//         );
//
//         /// 🔥 HTML ની કોઈ પણ ભૂલ સીધી screen પર
//         controller.addJavaScriptHandler(
//           handlerName: "jsError",
//           callback: (args) {
//             _gotMessageFromPage = true;
//             final String msg = args.isNotEmpty ? args.first.toString() : "";
//             debugPrint("❌ TRYON JS ERROR => $msg");
//             if (!mounted) return null;
//             setState(() => _error = "Try-on error:\n$msg");
//             return null;
//           },
//         );
//
//         controller.addJavaScriptHandler(
//           handlerName: "photo",
//           callback: (args) {
//             if (args.isNotEmpty) _onPhoto(args.first.toString());
//             return null;
//           },
//         );
//       },
//
//       /// 🔥 WebView ને camera આપો
//       onPermissionRequest: (controller, request) async {
//         return PermissionResponse(
//           resources: request.resources,
//           action: PermissionResponseAction.GRANT,
//         );
//       },
//
//       /// 🔥 Page load ના થાય (દા.ત. ERR_CLEARTEXT_NOT_PERMITTED,
//       /// ERR_CONNECTION_REFUSED) તો સાચું કારણ બતાવો
//       onReceivedError: (controller, request, error) {
//         if (request.isForMainFrame != true) return;
//
//         debugPrint(
//           "❌ TRYON PAGE ERROR => ${error.type} | ${error.description} | ${request.url}",
//         );
//
//         if (!mounted) return;
//         setState(() {
//           _pageReady = false;
//           _error = "Try-on page did not load.\n${error.description}";
//         });
//       },
//
//       onReceivedHttpError: (controller, request, response) {
//         if (request.isForMainFrame != true) return;
//
//         debugPrint(
//           "❌ TRYON HTTP ERROR => ${response.statusCode} | ${request.url}",
//         );
//
//         if (!mounted) return;
//         setState(() {
//           _pageReady = false;
//           _error = "Try-on page not found (${response.statusCode}).\n"
//               "Check ${TryOnPages.assetFolder}/ in pubspec.yaml";
//         });
//       },
//
//       onLoadStart: (controller, url) {
//         debugPrint("🌐 TRYON LOAD START => $url");
//       },
//
//       onLoadStop: (controller, url) async {
//         debugPrint("🌐 TRYON LOAD STOP => $url");
//         final title = await controller.getTitle();
//         debugPrint("🌐 TRYON PAGE TITLE => $title");
//       },
//
//       onConsoleMessage: (controller, msg) {
//         debugPrint("TRYON JS => ${msg.message}");
//       },
//     );
//   }
//
//   Widget _bottomControls() {
//     return Container(
//       padding: EdgeInsets.fromLTRB(
//         16,
//         14,
//         16,
//         14 + MediaQuery.of(context).padding.bottom,
//       ),
//       decoration: BoxDecoration(
//         color: Colors.black.withOpacity(0.55),
//         borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
//       ),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           /// SIZE
//           Row(
//             children: [
//               const Icon(Icons.photo_size_select_small_rounded,
//                   color: Colors.white70, size: 18),
//               Expanded(
//                 child: Slider(
//                   value: _size,
//                   min: 0.6,
//                   max: 1.6,
//                   divisions: 20,
//                   activeColor: const Color(0xffD9B86C),
//                   inactiveColor: Colors.white24,
//                   onChanged: (v) {
//                     setState(() => _size = v);
//                     _js("window.setSize($v);");
//                   },
//                 ),
//               ),
//               const Icon(Icons.photo_size_select_large_rounded,
//                   color: Colors.white70, size: 22),
//             ],
//           ),
//
//           /// 🔥 CHAIN: ઉપર / નીચે
//           if (_isChain)
//             Row(
//               children: [
//                 const Icon(Icons.keyboard_arrow_up_rounded,
//                     color: Colors.white70, size: 22),
//                 Expanded(
//                   child: Slider(
//                     value: _offset,
//                     min: -1,
//                     max: 1,
//                     divisions: 20,
//                     activeColor: const Color(0xffD9B86C),
//                     inactiveColor: Colors.white24,
//                     onChanged: (v) {
//                       setState(() => _offset = v);
//                       _js("window.setOffset($v);");
//                     },
//                   ),
//                 ),
//                 const Icon(Icons.keyboard_arrow_down_rounded,
//                     color: Colors.white70, size: 22),
//               ],
//             ),
//
//           const SizedBox(height: 6),
//
//           Row(
//             children: [
//               /// SHOW POINTS
//               Expanded(
//                 child: OutlinedButton.icon(
//                   onPressed: () {
//                     setState(() => _showPoints = !_showPoints);
//                     _js("window.setShowPoints($_showPoints);");
//                   },
//                   icon: Icon(
//                     _showPoints
//                         ? Icons.visibility_rounded
//                         : Icons.visibility_outlined,
//                     size: 18,
//                   ),
//                   label: Text(_showPoints ? "Hide points" : "Show points"),
//                   style: OutlinedButton.styleFrom(
//                     foregroundColor: Colors.white,
//                     side: const BorderSide(color: Colors.white38),
//                     padding: const EdgeInsets.symmetric(vertical: 13),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(10),
//                     ),
//                   ),
//                 ),
//               ),
//
//               const SizedBox(width: 10),
//
//               /// TAKE PHOTO
//               Expanded(
//                 child: Material(
//                   color: Colors.transparent,
//                   child: InkWell(
//                     onTap: _sharing
//                         ? null
//                         : () {
//                       setState(() => _sharing = true);
//                       _js("window.takePhoto();");
//
//                       /// JS જવાબ ના આપે તો loader અટકી ના રહે
//                       Future.delayed(const Duration(seconds: 8), () {
//                         if (mounted && _sharing) {
//                           setState(() => _sharing = false);
//                         }
//                       });
//                     },
//                     borderRadius: BorderRadius.circular(10),
//                     child: Ink(
//                       height: 46,
//                       decoration: BoxDecoration(
//                         gradient: const LinearGradient(colors: [_navy, _blue]),
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                       child: Center(
//                         child: _sharing
//                             ? const SizedBox(
//                           width: 18,
//                           height: 18,
//                           child: CircularProgressIndicator(
//                             strokeWidth: 2,
//                             color: Colors.white,
//                           ),
//                         )
//                             : const Row(
//                           mainAxisAlignment: MainAxisAlignment.center,
//                           children: [
//                             Icon(Icons.camera_alt_rounded,
//                                 color: Colors.white, size: 18),
//                             SizedBox(width: 6),
//                             Text(
//                               "Photo & Share",
//                               style: TextStyle(
//                                 color: Colors.white,
//                                 fontWeight: FontWeight.w700,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _roundIcon(IconData icon, VoidCallback onTap) {
//     return InkWell(
//       onTap: onTap,
//       borderRadius: BorderRadius.circular(10),
//       child: Container(
//         width: 40,
//         height: 40,
//         alignment: Alignment.center,
//         decoration: BoxDecoration(
//           color: Colors.black.withOpacity(0.45),
//           borderRadius: BorderRadius.circular(10),
//         ),
//         child: Icon(icon, color: Colors.white, size: 22),
//       ),
//     );
//   }
// }

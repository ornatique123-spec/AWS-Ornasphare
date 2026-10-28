// import 'dart:math';
//
// import 'package:camera/camera.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
//
// class ArViewScreen extends StatefulWidget {
//
//   final String imageUrl;
//
//   const ArViewScreen({
//     super.key,
//     required this.imageUrl,
//   });
//
//   @override
//   State<ArViewScreen> createState() =>
//       _ArViewScreenState();
// }
//
// class _ArViewScreenState
//     extends State<ArViewScreen> {
//
//   CameraController? controller;
//
//   late PoseDetector poseDetector;
//
//   bool isBusy = false;
//
//   Offset wristPosition =
//   const Offset(150, 300);
//
//   double wristAngle = 0;
//
//   // 🔥 SMOOTHING
//   double smoothX = 150;
//
//   double smoothY = 300;
//
//   @override
//   void initState() {
//
//     super.initState();
//
//     poseDetector = PoseDetector(
//
//       options: PoseDetectorOptions(
//         mode: PoseDetectionMode.stream,
//       ),
//     );
//
//     initCamera();
//   }
//
//   // =========================
//   // INIT CAMERA
//   // =========================
//   Future<void> initCamera() async {
//
//     final cameras =
//     await availableCameras();
//
//     final frontCamera =
//     cameras.firstWhere(
//
//           (camera) =>
//
//       camera.lensDirection ==
//           CameraLensDirection.front,
//     );
//
//     controller = CameraController(
//
//       frontCamera,
//
//       ResolutionPreset.medium,
//
//       enableAudio: false,
//     );
//
//     await controller!.initialize();
//
//     await startImageStream();
//
//     if (mounted) {
//
//       setState(() {});
//     }
//   }
//
//   // =========================
//   // START IMAGE STREAM
//   // =========================
//   Future<void> startImageStream() async {
//
//     await controller!.startImageStream(
//
//           (CameraImage image) async {
//
//         if (isBusy) return;
//
//         isBusy = true;
//
//         try {
//
//           final WriteBuffer
//           allBytes = WriteBuffer();
//
//           for (Plane plane
//           in image.planes) {
//
//             allBytes.putUint8List(
//               plane.bytes,
//             );
//           }
//
//           final bytes =
//           allBytes.done().buffer.asUint8List();
//
//           final inputImage =
//           InputImage.fromBytes(
//
//             bytes: bytes,
//
//             metadata:
//             InputImageMetadata(
//
//               size: Size(
//
//                 image.width.toDouble(),
//
//                 image.height.toDouble(),
//               ),
//
//               rotation:
//               InputImageRotation
//                   .rotation0deg,
//
//               format:
//               InputImageFormat
//                   .nv21,
//
//               bytesPerRow:
//               image.planes.first
//                   .bytesPerRow,
//             ),
//           );
//
//           final poses =
//           await poseDetector
//               .processImage(
//             inputImage,
//           );
//
//           if (poses.isNotEmpty) {
//
//             final pose = poses.first;
//
//             // 🔥 LEFT WRIST
//             final wrist =
//             pose.landmarks[
//             PoseLandmarkType
//                 .leftWrist];
//
//             // 🔥 LEFT ELBOW
//             final elbow =
//             pose.landmarks[
//             PoseLandmarkType
//                 .leftElbow];
//
//             if (wrist != null &&
//                 elbow != null) {
//
//               // =========================
//               // ANGLE
//               // =========================
//               final dx =
//                   wrist.x - elbow.x;
//
//               final dy =
//                   wrist.y - elbow.y;
//
//               double targetAngle =
//               atan2(dy, dx);
//
//               // 🔥 SMOOTH ROTATION
//               wristAngle =
//                   wristAngle +
//                       ((targetAngle -
//                           wristAngle) *
//                           0.15);
//
//               // =========================
//               // SCREEN MAP
//               // =========================
//               final screenWidth =
//                   MediaQuery.of(context)
//                       .size
//                       .width;
//
//               final screenHeight =
//                   MediaQuery.of(context)
//                       .size
//                       .height;
//
//               // 🔥 CAMERA → SCREEN
//               double mappedX =
//                   (wrist.x /
//                       image.width) *
//                       screenWidth;
//
//               double mappedY =
//                   (wrist.y /
//                       image.height) *
//                       screenHeight;
//
//               // =========================
//               // SMOOTH POSITION
//               // =========================
//               smoothX =
//                   smoothX +
//                       ((mappedX -
//                           smoothX) *
//                           0.20);
//
//               smoothY =
//                   smoothY +
//                       ((mappedY -
//                           smoothY) *
//                           0.20);
//
//               if (mounted) {
//
//                 setState(() {
//
//                   wristPosition =
//                       Offset(
//                         smoothX,
//                         smoothY,
//                       );
//                 });
//               }
//             }
//           }
//         } catch (e) {
//
//           debugPrint(
//             "POSE ERROR => $e",
//           );
//         }
//
//         isBusy = false;
//       },
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//
//     if (controller == null ||
//         !controller!
//             .value
//             .isInitialized) {
//
//       return const Scaffold(
//
//         body: Center(
//           child:
//           CircularProgressIndicator(),
//         ),
//       );
//     }
//
//     return Scaffold(
//
//       backgroundColor: Colors.black,
//
//       body: Stack(
//
//         children: [
//
//           // =========================
//           // CAMERA
//           // =========================
//           Positioned.fill(
//
//             child: CameraPreview(
//               controller!,
//             ),
//           ),
//
//           // =========================
//           // WATCH TRY ON
//           // =========================
//           Positioned(
//
//             // 🔥 FRONT CAMERA MIRROR FIX
//             left:
//             MediaQuery.of(context)
//                 .size
//                 .width -
//                 wristPosition.dx -
//                 45,
//
//             top:
//             wristPosition.dy - 35,
//
//             child: Transform.rotate(
//
//               angle: wristAngle,
//
//               child: Image.network(
//
//                 widget.imageUrl
//                     .replaceAll(
//                   "[",
//                   "",
//                 )
//                     .replaceAll(
//                   "]",
//                   "",
//                 )
//                     .trim(),
//
//                 width: 90,
//
//                 fit: BoxFit.contain,
//
//                 loadingBuilder:
//                     (
//                     context,
//                     child,
//                     progress,
//                     ) {
//
//                   if (progress ==
//                       null) {
//
//                     return child;
//                   }
//
//                   return const SizedBox(
//
//                     width: 60,
//                     height: 60,
//
//                     child: Center(
//
//                       child:
//                       CircularProgressIndicator(),
//                     ),
//                   );
//                 },
//
//                 errorBuilder:
//                     (
//                     context,
//                     error,
//                     stackTrace,
//                     ) {
//
//                   return const Icon(
//
//                     Icons.error,
//
//                     color: Colors.red,
//
//                     size: 50,
//                   );
//                 },
//               ),
//             ),
//           ),
//
//           // =========================
//           // TOP BAR
//           // =========================
//           Positioned(
//
//             top: 55,
//             left: 20,
//             right: 20,
//
//             child: Row(
//
//               mainAxisAlignment:
//               MainAxisAlignment
//                   .spaceBetween,
//
//               children: [
//
//                 // BACK
//                 InkWell(
//
//                   onTap: () {
//
//                     Navigator.pop(
//                       context,
//                     );
//                   },
//
//                   child: Container(
//
//                     padding:
//                     const EdgeInsets
//                         .all(12),
//
//                     decoration:
//                     BoxDecoration(
//
//                       color:
//                       Colors.black54,
//
//                       borderRadius:
//                       BorderRadius
//                           .circular(
//                         14,
//                       ),
//                     ),
//
//                     child: const Icon(
//
//                       Icons.arrow_back,
//
//                       color:
//                       Colors.white,
//                     ),
//                   ),
//                 ),
//
//                 // TITLE
//                 Container(
//
//                   padding:
//                   const EdgeInsets
//                       .symmetric(
//                     horizontal: 18,
//                     vertical: 10,
//                   ),
//
//                   decoration:
//                   BoxDecoration(
//
//                     color:
//                     Colors.black54,
//
//                     borderRadius:
//                     BorderRadius
//                         .circular(
//                       14,
//                     ),
//                   ),
//
//                   child: const Text(
//
//                     "Watch Try On",
//
//                     style: TextStyle(
//
//                       color:
//                       Colors.white,
//
//                       fontSize: 16,
//
//                       fontWeight:
//                       FontWeight.bold,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//
//           // =========================
//           // BOTTOM INFO
//           // =========================
//           Positioned(
//
//             bottom: 35,
//             left: 20,
//             right: 20,
//
//             child: Container(
//
//               padding:
//               const EdgeInsets.all(
//                 14,
//               ),
//
//               decoration:
//               BoxDecoration(
//
//                 color: Colors.black54,
//
//                 borderRadius:
//                 BorderRadius.circular(
//                   16,
//                 ),
//               ),
//
//               child: const Text(
//
//                 "Keep wrist visible for best try-on result",
//
//                 textAlign: TextAlign.center,
//
//                 style: TextStyle(
//
//                   color: Colors.white,
//
//                   fontSize: 14,
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   @override
//   void dispose() {
//
//     controller?.dispose();
//
//     poseDetector.close();
//
//     super.dispose();
//   }
// }
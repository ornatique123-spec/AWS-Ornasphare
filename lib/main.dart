import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:provider/provider.dart';

import 'Api_Constant/api_helper.dart';
import 'Extra/HomeRefreshProvider.dart';
import 'Extra/ItemProvider.dart';
import 'Extra/NotificationProvider.dart';
import 'Extra/PremiumColors.dart';
import 'Offline Data/sync_service.dart';
import 'Splash/SplashScreen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ApiHelper().loadTokenFromPrefs();

  // ✅ Show status bar
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
  );

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // Android
      statusBarBrightness: Brightness.light,    // iOS
    ),
  );


  PremiumColors.selectedTheme = 0;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ItemProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(
          create: (_) => HomeRefreshProvider(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription? _internetSubscription;

  @override
  void initState() {
    super.initState();
    Connectivity().onConnectivityChanged.listen((_) {
      SyncService.instance.syncPendingData();
    });
    //_listenInternet();
  }

  void _listenInternet() {
    _internetSubscription =
        InternetConnection().onStatusChange.listen((status) {

          if (status == InternetStatus.disconnected) {
            AppDialog.showNoInternetDialog();
          } else {
            AppDialog.hideNoInternetDialog();
          }
        });
  }

  @override
  void dispose() {
    _internetSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'OrnaSphere',

      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F172A),
          brightness: Brightness.dark,
        ),
      ),

      home: const SplashScreen(),
    );
  }
}
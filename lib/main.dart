import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:parking_management_system/auth_wrapper.dart';
import 'package:parking_management_system/resources/app_theme.dart';
import 'package:parking_management_system/resources/widget/internet_connection_banner.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:parking_management_system/theme_controller.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:window_manager/window_manager.dart';
import 'services/app_title_bar.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  final isDesktop =
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);
  if (isDesktop) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(1440, 900),
      minimumSize: Size(880, 600),
      center: true,
      title: 'Parking Management',
      titleBarStyle: TitleBarStyle.hidden,
      backgroundColor: Color(0xFFF5F8F5),
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  // final auth = Auth();
  // await auth.logoutOnAppStart();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeMode,
      builder: (context, mode, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,

          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: mode,
          themeAnimationDuration: const Duration(milliseconds: 350),
          themeAnimationCurve: Curves.easeInOutCubic,
          home: const _AppWindowShell(
            child: InternetConnectionBanner(child: AuthWrapper()),
          ),
        );
      },
    );
  }
}

class _AppWindowShell extends StatelessWidget {
  const _AppWindowShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux);
    if (!isDesktop) return child;

    return Column(
      children: [
        const AdminTitleBar(),
        Expanded(child: child),
      ],
    );
  }
}

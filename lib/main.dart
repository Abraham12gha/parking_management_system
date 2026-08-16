import 'package:flutter/material.dart';
import 'package:parking_management_system/auth_wrapper.dart';
import 'package:parking_management_system/resources/app_theme.dart';
import 'package:parking_management_system/resources/widget/internet_connection_banner.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:parking_management_system/theme_controller.dart';
import 'app_settings.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
      const MyApp()
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void changeTheme(bool isDark) {
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

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
            home: InternetConnectionBanner(
          child: AuthWrapper()
            )
            );
          },
    );
  }
}
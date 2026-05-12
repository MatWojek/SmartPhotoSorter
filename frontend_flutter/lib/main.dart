import 'package:flutter/material.dart';
import 'features/home/home_page.dart';
import 'core/app_theme.dart';
import 'core/theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = ThemeController();
  await controller.load();
  runApp(SmartPhotoOrganizerApp(controller: controller));
}

class SmartPhotoOrganizerApp extends StatelessWidget {
  final ThemeController controller;
  const SmartPhotoOrganizerApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ThemeControllerProvider(
      controller: controller,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'SmartPhotoOrganizer',
            theme: classicLightTheme(),
            darkTheme: classicDarkTheme(),
            themeMode: controller.mode,
            home: const HomePage(),
          );
        },
      ),
    );
  }
}
import 'package:flutter/material.dart';
import '../auth/auth_login_page.dart';
import '../auth/auth_registration_page.dart';
import '../../core/theme_controller.dart';

class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final bool loggedIn;
  final void Function(bool loggedIn, {String? userId, String? token}) onAuthChanged;

  const AppTopBar({
    super.key,
    required this.loggedIn,
    required this.onAuthChanged,
  });

  @override
  Widget build(BuildContext context) {
    final themeController = ThemeControllerProvider.of(context);
    final isDark = themeController.mode == ThemeMode.dark;
    return AppBar(
      title: const Text('SmartPhotoSorter'),
      actions: [
        IconButton(
          tooltip: isDark ? 'Light mode' : 'Dark mode',
          icon: Icon(isDark ? Icons.wb_sunny_outlined : Icons.dark_mode_outlined),
          onPressed: () => themeController.toggle(),
        ),
        if (!loggedIn) ...[
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AuthLoginPage(onAuthChanged: onAuthChanged),
                ),
              );
            },
            child: const Text('Login'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AuthRegistrationPage(onAuthChanged: onAuthChanged),
                ),
              );
            },
            child: const Text('Register'),
          ),
        ] else ...[
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () => onAuthChanged(false),
          ),
        ],
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
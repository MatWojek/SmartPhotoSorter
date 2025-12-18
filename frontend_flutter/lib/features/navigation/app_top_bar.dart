import 'package:flutter/material.dart';

class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final bool loggedIn;
  final VoidCallback onLoginToggle;

  const AppTopBar({super.key, required this.loggedIn, required this.onLoginToggle});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('SmartPhotoOrganizer'),
      actions: [
        IconButton(
          icon: Icon(loggedIn ? Icons.logout : Icons.login),
          onPressed: onLoginToggle,
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
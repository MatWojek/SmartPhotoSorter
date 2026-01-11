import 'package:flutter/material.dart';
import '../auth/auth_login_page.dart';
import '../auth/auth_registration_page.dart';
import '../../core/theme_controller.dart';
import 'person_search.dart';
import 'filter_bottom_sheet.dart';

class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final bool loggedIn;
  final void Function(bool loggedIn, {String? userId, String? token}) onAuthChanged;

  final String? userId;
  final ValueChanged<String>? onSearchPerson;
  final void Function({required List<String> persons, Map<String, dynamic>? attributes})? onFiltersApplied;

  const AppTopBar({
    super.key,
    required this.loggedIn,
    required this.onAuthChanged,
    this.userId,
    this.onSearchPerson,
    this.onFiltersApplied,
  });

  @override
  Widget build(BuildContext context) {
    final themeController = ThemeControllerProvider.of(context);
    final isDark = themeController.mode == ThemeMode.dark;
    final canQuery = loggedIn && (userId != null && userId!.isNotEmpty);

    return AppBar(
      title: const Text('SmartPhotoSorter'),
      actions: [
        IconButton(
          tooltip: isDark ? 'Light mode' : 'Dark mode',
          icon: Icon(isDark ? Icons.wb_sunny_outlined : Icons.dark_mode_outlined),
          onPressed: () => themeController.toggle(),
        ),
        if (canQuery) ...[
          IconButton(
            tooltip: 'Search Person',
            icon: const Icon(Icons.search),
            onPressed: () async {
              final selected = await showSearch<String>(
                context: context,
                delegate: PersonSearchDelegate(userId: userId!),
              );
              if (selected != null && selected.trim().isNotEmpty) {
                onSearchPerson!(selected.trim());
              }
            },
          ),
          IconButton(
            tooltip: 'Filter',
            icon: const Icon(Icons.filter_list),
            onPressed: () async {
              final res = await showModalBottomSheet<Map<String, dynamic>>(
                context: context,
                isScrollControlled: true,
                builder: (_) => FilterBottomSheet(userId: userId!),
              );
              if (res != null && onFiltersApplied != null) {
                final persons = (res['persons'] as List<dynamic>? ?? []).cast<String>();
                final attributes = (res['attributes'] as Map<String, dynamic>?) ?? {};
                onFiltersApplied!(persons: persons, attributes: attributes);
              }
            },
          ),
        ],
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
          const SizedBox(width: 8),
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
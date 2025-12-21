import 'package:flutter/material.dart';
import '../../models/person.dart';
import '../navigation/app_top_bar.dart';
import '../../core/theme_controller.dart';

class PersonDetailPage extends StatelessWidget {
  final Person person;

  const PersonDetailPage({super.key, required this.person});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(person.name),
        actions: [
          Builder(builder: (context) {
            final controller = ThemeControllerProvider.of(context);
            final isDark = controller.mode == ThemeMode.dark;
            return IconButton(
              tooltip: isDark ? 'Light mode' : 'Dark mode',
              icon: Icon(isDark ? Icons.wb_sunny_outlined : Icons.dark_mode_outlined),
              onPressed: () => controller.toggle(),
            );
          }),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4, 
          crossAxisSpacing: 12, 
          mainAxisSpacing: 12, 
        ), 
        itemCount: person.photos,
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.image, color: Theme.of(context).colorScheme.onSecondaryContainer),
          );
        },
      ),
    );
  }
}
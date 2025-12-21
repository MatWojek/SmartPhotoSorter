import 'package:flutter/material.dart';

class FolderDropZone extends StatelessWidget {
  const FolderDropZone({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
        ),
        child: InkWell(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Choose folder (mock action)')),
            );
          }, 
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.drive_folder_upload, size: 30, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 8),
                Text('Choose or drop folder with images',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 
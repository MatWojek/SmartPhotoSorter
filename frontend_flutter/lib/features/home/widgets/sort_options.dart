import 'dart:io';
import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import 'progress_overlay.dart';
import 'training_folders_dialog.dart';

enum RunMode { local, database }

class SortOptionsPanel extends StatefulWidget {
  final String? selectedFolder;
  final String? currentUserId; // optional: DB indexing

  const SortOptionsPanel({super.key, required this.selectedFolder, this.currentUserId});

  @override
  State<SortOptionsPanel> createState() => _SortOptionsPanelState();
}

class _SortOptionsPanelState extends State<SortOptionsPanel> {
  bool removeDuplicates = false;
  bool sortPhotos = false;
  bool manualCorrections = false; // future extension

  Future<RunMode?> _chooseRunMode(BuildContext context) async {
    return showDialog<RunMode>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Select a mode'),
        content: const Text('Perform the operation locally or index in the database?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, RunMode.local), child: const Text('Locally')),
          FilledButton(onPressed: () => Navigator.pop(context, RunMode.database), child: const Text('Database')),
        ],
      ),
    );
  }

  Future<void> _startLocal(BuildContext context, String folder) async {
    final Directory baseDir = Directory(folder);
    final outputBase = Directory('${baseDir.path}${Platform.pathSeparator}sorted').path;
    final unknownFolder = Directory('$outputBase${Platform.pathSeparator}unknown').path;

    Map<String, String> trainingFolders = {};
    if (sortPhotos) {
      final res = await showDialog<Map<String, String>>(
        context: context,
        builder: (_) => const TrainingFoldersDialog(),
      );
      if (res == null || res.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No training folders.')));
        return;
      }
      trainingFolders = res;
    }

    // Mode "only dupliates": call sort-local without training folders
    final resp = await ApiService.startSortLocal(
      trainingFolders: trainingFolders,
      unsortedFolder: folder,
      outputBase: outputBase,
      unknownFolder: unknownFolder,
    );
    final taskId = resp['task_id'] as String;
    final wsUrl = ApiService.progressWsUrl(taskId);
    final sseUri = ApiService.progressSseUri(taskId);

    if (!mounted) return;
    await showDialog(
      barrierDismissible: false,
      context: context,
      builder: (_) => ProgressOverlay(wsUrl: wsUrl, sseUri: sseUri),
    );
  }

  Future<void> _startDb(BuildContext context, String folder) async {
    String? userId = widget.currentUserId;
    if (userId == null || userId.isEmpty) {
      userId = await showDialog<String>(
        context: context,
        builder: (_) {
          final ctrl = TextEditingController();
          return AlertDialog(
            title: const Text('Give user_id'),
            content: TextField(
              controller: ctrl,
              decoration: const InputDecoration(labelText: 'user_id'),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('OK')),
            ],
          );
        },
      );
      if (userId == null || userId.isEmpty) return;
    }

    Map<String, String>? trainingFolders;
    if (sortPhotos) {
      final res = await showDialog<Map<String, String>>(
        context: context,
        builder: (_) => const TrainingFoldersDialog(),
      );
      trainingFolders = res;
    }

    final resp = await ApiService.startIndexDb(
      userId: userId,
      folder: folder,
      trainingFolders: trainingFolders,
    );
    final taskId = resp['task_id'] as String;
    final wsUrl = ApiService.progressWsUrl(taskId);
    final sseUri = ApiService.progressSseUri(taskId);

    if (!mounted) return;
    await showDialog(
      barrierDismissible: false,
      context: context,
      builder: (_) => ProgressOverlay(wsUrl: wsUrl, sseUri: sseUri),
    );
  }

  Future<void> _handleAction(BuildContext context) async {
    final folder = widget.selectedFolder;
    if (folder == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Najpierw wybierz folder.')));
      return;
    }
    // Dodatkowa weryfikacja
    if (!Directory(folder).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wybrany folder nie istnieje.')));
      return;
    }
    if (!removeDuplicates && !sortPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zaznacz co najmniej jedną opcję.')));
      return;
    }

    final mode = await _chooseRunMode(context);
    if (mode == null) return;

    if (!mounted) return;
    if (mode == RunMode.local) {
      await _startLocal(context, folder);
    } else {
      await _startDb(context, folder);
    }
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.selectedFolder == null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 4,
              children: [
                FilterChip(
                  selected: removeDuplicates,
                  onSelected: disabled ? null : (v) => setState(() => removeDuplicates = v),
                  label: const Text('Delete duplicates'),
                ),
                FilterChip(
                  selected: sortPhotos,
                  onSelected: disabled ? null : (v) => setState(() => sortPhotos = v),
                  label: const Text('Sort Images'),
                ),
                // optional switch for the future
                // FilterChip(
                //   selected: manualCorrections,
                //   onSelected: disabled ? null : (v) => setState(() => manualCorrections = v),
                //   label: const Text('Manualne korekty w trakcie'),
                // ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: disabled ? null : () => _handleAction(context),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Action'),
          ),
        ],
      ),
    );
  }
}
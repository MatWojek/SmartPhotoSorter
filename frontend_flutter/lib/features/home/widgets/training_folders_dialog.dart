import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

class TrainingFoldersDialog extends StatefulWidget {
  const TrainingFoldersDialog({super.key});
  @override
  State<TrainingFoldersDialog> createState() => _TrainingFoldersDialogState();
}

class _TrainingFoldersDialogState extends State<TrainingFoldersDialog> {
  final List<MapEntry<String, String>> _pairs = [];

  String _folderBaseName(String path) {
    final parts = path.split(RegExp(r'[\\/]+'));
    return parts.isNotEmpty ? parts.last : path;
  }

  String _uniqueName(String base) {
    var name = base; 
    var i = 2; 
    final existing = _pairs.map((e) => e.key).toSet(); 
    while (existing.contains(name)) {
      name = '$base ($i)';
      i++;
    }
    return name;
  }

  Future<void> _addPair() async {
    final nameCtrl = TextEditingController();
    String? folder;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add person and folder'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name or Username')),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: Text(folder ?? 'No folder selected', overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () async {
                      final picked = await getDirectoryPath(confirmButtonText: 'Select');
                      if (picked != null) {
                        setState(() => folder = picked);
                      }
                    },
                    child: const Text('Select folder'),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              var name = nameCtrl.text.trim();
              if (name.isEmpty && folder != null) {
                name = _folderBaseName(folder!);
              }
              if (name.isNotEmpty && folder != null) {
                _pairs.add(MapEntry(_uniqueName(name), folder!));
                Navigator.of(context).pop();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    setState(() {});
  }

  Future<void> _bulkImportFromParent() async {
    final parent = await getDirectoryPath(confirmButtonText: 'Select');
    if (parent == null) return;
    final dir = Directory(parent);
    if (!dir.existsSync()) return;

    final subs = dir.listSync(followLinks: false).whereType<Directory>();
    for (final d in subs) {
      final name = _uniqueName(_folderBaseName(d.path));
      _pairs.add(MapEntry(name, d.path));
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Training folders'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_pairs.isEmpty)
              const Text('Add at least one pair: person → photo folder.'),
            for (final e in _pairs)
              ListTile(
                dense: true,
                leading: const Icon(Icons.person),
                title: Text(e.key),
                subtitle: Text(e.value, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => setState(() => _pairs.remove(e)),
                ),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add),
                    onPressed: _addPair,
                    label: const Text('Add person + folder'),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.folder_open),
                    onPressed: _bulkImportFromParent,
                    label: const Text('Import subfolders as persons'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (_pairs.isEmpty) return;
            final map = {for (final e in _pairs) e.key: e.value};
            Navigator.of(context).pop(map);
          },
          child: const Text('Use'),
        ),
      ],
    );
  }
}
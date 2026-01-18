import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class TrainingFoldersDialog extends StatefulWidget {
  final String? currentUserId;
  const TrainingFoldersDialog({super.key, this.currentUserId});
  @override
  State<TrainingFoldersDialog> createState() => _TrainingFoldersDialogState();
}

class _TrainingFoldersDialogState extends State<TrainingFoldersDialog> {
  final List<MapEntry<String, String>> _pairs = [];
  String? _selectedFolder;

  @override
  void dispose() {
    super.dispose();
  }

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

  Directory _manualTrainBase() {
    final home = Platform.environment['HOME'] ?? Directory.current.path;
    final userPart = (widget.currentUserId != null && widget.currentUserId!.isNotEmpty)
        ? widget.currentUserId!
        : 'local';
    final dir = Directory('$home${Platform.pathSeparator}.smartphotosorter${Platform.pathSeparator}train_manual${Platform.pathSeparator}$userPart');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  Future<void> _addSinglePhoto() async {
    final img = await openFile(acceptedTypeGroups: [
      const XTypeGroup(label: 'images', extensions: ['jpg','jpeg','png','bmp','gif','webp','tiff'])
    ]);
    if (img == null) return;

    final nameCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Label the photo'),
        content: TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Person name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
        ],
      ),
    );
    if (ok != true) return;
    final person = _uniqueName(nameCtrl.text.trim());
    if (person.isEmpty) return;

    final base = _manualTrainBase();
    final targetDir = Directory('${base.path}${Platform.pathSeparator}$person');
    if (!targetDir.existsSync()) targetDir.createSync(recursive: true);
    final srcPath = img.path;
    final fileName = srcPath.split(RegExp(r'[\\/]')).last;
    final target = File('${targetDir.path}${Platform.pathSeparator}$fileName');
    try {
      await File(srcPath).copy(target.path);
      _pairs.add(MapEntry(person, targetDir.path));
      setState(() {});
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot copy the selected photo.')));
    }
  }

  Future<void> _addPair() async {
    final nameCtrl = TextEditingController();

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
                  Expanded(child: Text(_selectedFolder ?? 'Select a folder', overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () async {
                      final picked = await getDirectoryPath(confirmButtonText: 'Select');
                      if (picked != null) {
                        setState(() => _selectedFolder = picked);
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
              if (name.isEmpty && _selectedFolder != null) {
                name = _folderBaseName(_selectedFolder!);
              }
              if (name.isNotEmpty && _selectedFolder != null) {
                _pairs.add(MapEntry(_uniqueName(name), _selectedFolder!));
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
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 420),
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
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
                          icon: const Icon(Icons.add_photo_alternate),
                          onPressed: _addSinglePhoto,
                          label: const Text('Add person + photo'),
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.folder_open),
                          onPressed: _bulkImportFromParent,
                          label: const Text('Import subfolders as persons'),
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.auto_awesome),
                          onPressed: () async {
                            final prefs = await SharedPreferences.getInstance();
                            final key = widget.currentUserId != null && widget.currentUserId!.isNotEmpty
                                ? 'train_data_${widget.currentUserId}'
                                : 'train_data_local';
                            final jsonStr = prefs.getString(key);
                            if (jsonStr == null || jsonStr.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No saved train data. Add training folders first.')));
                              return;
                            }
                            try {
                              final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
                              final Map<String, String> mapped = decoded.map((k, v) => MapEntry(k, v.toString()));
                              if (mapped.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No saved train data.')));
                                return;
                              }
                              if (mounted) Navigator.of(context).pop(mapped);
                            } catch (_) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot load saved train data.')));
                            }
                          },
                          label: const Text('Use train data'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (_pairs.isEmpty) return;
            final map = {for (final e in _pairs) e.key: e.value};
            // Persist for future reuse
            () async {
              final prefs = await SharedPreferences.getInstance();
              final key = widget.currentUserId != null && widget.currentUserId!.isNotEmpty
                  ? 'train_data_${widget.currentUserId}'
                  : 'train_data_local';
              await prefs.setString(key, jsonEncode(map));
            }();
            Navigator.of(context).pop(map);
          },
          child: const Text('Use'),
        ),
      ],
    );
  }
}